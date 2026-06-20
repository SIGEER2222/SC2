[CmdletBinding()]
param(
    [int]$StaleMinutes = 45,
    [int]$CooldownMinutes = 20,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$sessionIds = @(
    '019ee5bd-b140-7560-af98-542e6c88d406',
    '019ee32a-df91-71f3-8d5a-fde708404894'
)

$codexHome = Join-Path $env:USERPROFILE '.codex'
$goalsDb = Join-Path $codexHome 'goals_1.sqlite'
$sessionsRoot = Join-Path $codexHome 'sessions'
$resumeStatePath = Join-Path $codexHome 'automations\goal-monitor-state.json'
$codexExe = Join-Path $codexHome '.sandbox-bin\codex.exe'
$resumeHelperPath = Join-Path $PSScriptRoot 'resume-codex-thread.ps1'

if (-not (Test-Path $goalsDb)) {
    throw "Goals database not found: $goalsDb"
}
if (-not (Test-Path $sessionsRoot)) {
    throw "Sessions root not found: $sessionsRoot"
}
if (-not (Test-Path $codexExe)) {
    throw "Codex executable not found: $codexExe"
}
if (-not (Test-Path $resumeHelperPath)) {
    throw "Resume helper not found: $resumeHelperPath"
}

$resumeStateDir = Split-Path -Parent $resumeStatePath
if (-not (Test-Path $resumeStateDir)) {
    New-Item -ItemType Directory -Path $resumeStateDir | Out-Null
}

function Get-ResumeState {
    if (-not (Test-Path $resumeStatePath)) {
        return @{}
    }
    $raw = Get-Content -LiteralPath $resumeStatePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{}
    }
    return ConvertFrom-Json -InputObject $raw -AsHashtable
}

function Save-ResumeState {
    param(
        [hashtable]$State
    )
    $json = $State | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $resumeStatePath -Value $json -Encoding UTF8
}

function Get-ThreadGoalRows {
    param(
        [string]$ThreadId
    )

    $query = @"
import sqlite3, json, sys
db_path = sys.argv[1]
thread_id = sys.argv[2]
con = sqlite3.connect(db_path)
cur = con.cursor()
rows = cur.execute(
    'select thread_id, goal_id, objective, status, token_budget, tokens_used, time_used_seconds, created_at_ms, updated_at_ms from thread_goals where thread_id = ?',
    (thread_id,)
).fetchall()
print(json.dumps([
    {
        'thread_id': row[0],
        'goal_id': row[1],
        'objective': row[2],
        'status': row[3],
        'token_budget': row[4],
        'tokens_used': row[5],
        'time_used_seconds': row[6],
        'created_at_ms': row[7],
        'updated_at_ms': row[8],
    }
    for row in rows
], ensure_ascii=False))
"@

    $json = $query | python - $goalsDb $ThreadId

    if ([string]::IsNullOrWhiteSpace($json)) {
        return @()
    }

    return ConvertFrom-Json -InputObject $json
}

function Get-SessionFile {
    param(
        [string]$ThreadId
    )

    return Get-ChildItem -Path $sessionsRoot -Recurse -File -Filter "*$ThreadId*.jsonl" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Start-ResumeWindow {
    param(
        [string]$ThreadId
    )

    $arguments = @(
        '-NoExit',
        '-ExecutionPolicy', 'Bypass',
        '-File', $resumeHelperPath,
        '-ThreadId', $ThreadId
    )

    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Normal | Out-Null
}

$now = Get-Date
$resumeState = Get-ResumeState
$activityThreshold = $now.AddMinutes(-1 * $StaleMinutes)
$cooldownThreshold = $now.AddMinutes(-1 * $CooldownMinutes)
$results = @()

foreach ($sessionId in $sessionIds) {
    $goalRows = @(Get-ThreadGoalRows -ThreadId $sessionId)
    $activeGoal = $goalRows | Where-Object { $_.status -eq 'active' } | Sort-Object updated_at_ms -Descending | Select-Object -First 1
    $sessionFile = Get-SessionFile -ThreadId $sessionId

    $result = [ordered]@{
        thread_id = $sessionId
        checked_at = $now.ToString('o')
        has_active_goal = ($null -ne $activeGoal)
        goal_status = if ($activeGoal) { $activeGoal.status } else { $null }
        goal_updated_at = if ($activeGoal) { [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$activeGoal.updated_at_ms).LocalDateTime.ToString('o') } else { $null }
        session_file = if ($sessionFile) { $sessionFile.FullName } else { $null }
        session_last_write = if ($sessionFile) { $sessionFile.LastWriteTime.ToString('o') } else { $null }
        resumed = $false
        reason = $null
    }

    if (-not $activeGoal) {
        $result.reason = 'no-active-goal'
        $results += [pscustomobject]$result
        continue
    }

    if (-not $sessionFile) {
        $result.reason = 'no-session-file'
        $results += [pscustomobject]$result
        continue
    }

    if ($sessionFile.LastWriteTime -gt $activityThreshold) {
        $result.reason = 'session-recently-active'
        $results += [pscustomobject]$result
        continue
    }

    $lastResumeRaw = $resumeState[$sessionId]
    if ($lastResumeRaw) {
        $lastResumeAt = [datetime]$lastResumeRaw
        if ($lastResumeAt -gt $cooldownThreshold) {
            $result.reason = 'resume-cooldown'
            $results += [pscustomobject]$result
            continue
        }
    }

    if ($DryRun) {
        $result.reason = 'dry-run-stale-session'
    }
    else {
        Start-ResumeWindow -ThreadId $sessionId
        $resumeState[$sessionId] = $now.ToString('o')
        $result.resumed = $true
        $result.reason = 'stale-session-resumed'
    }
    $results += [pscustomobject]$result
}

Save-ResumeState -State $resumeState

$logDir = Join-Path $codexHome 'automations\logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logPath = Join-Path $logDir ("goal-monitor-" + $now.ToString('yyyyMMdd') + '.jsonl')
foreach ($result in $results) {
    Add-Content -LiteralPath $logPath -Value ($result | ConvertTo-Json -Compress) -Encoding UTF8
}

$results | ConvertTo-Json -Depth 6
