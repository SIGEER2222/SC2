[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("List", "New", "Validate")]
    [string]$Action,

    [string]$TaskId,
    [string]$BatchId,
    [string[]]$Set = @(),
    [string]$OutFile,
    [string]$BatchDir,

    [ValidateSet("text", "json")]
    [string]$Format = "text",

    [switch]$AllowUnresolved
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$taskRoot = Join-Path $projectRoot "docs\低成本模型任务包"
$manifestPath = Join-Path $taskRoot "task-manifest.json"
$validatorPath = Join-Path $projectRoot "scripts\low-cost-batch-validator\cli.mjs"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Task manifest not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-TaskEntry {
    param([Parameter(Mandatory = $true)][string]$Id)

    for ($index = 0; $index -lt $manifest.tasks.Count; $index++) {
        $entry = $manifest.tasks[$index]
        $code = "{0:D2}" -f ($index + 1)
        if ($Id -eq $code -or $Id -eq $entry.id) {
            return [pscustomobject]@{
                Code = $code
                Entry = $entry
            }
        }
    }

    throw "Unknown task id '$Id'. Use 01..07 or a manifest task id."
}

switch ($Action) {
    "List" {
        for ($index = 0; $index -lt $manifest.tasks.Count; $index++) {
            $entry = $manifest.tasks[$index]
            [pscustomobject]@{
                Code = "{0:D2}" -f ($index + 1)
                TaskId = $entry.id
                Prompt = $entry.prompt
                Outputs = ($entry.outputs -join "; ")
            }
        }
        break
    }

    "New" {
        if (-not $TaskId) {
            throw "-TaskId is required for Action New."
        }
        if (-not $BatchId) {
            throw "-BatchId is required for Action New."
        }
        if (-not $OutFile) {
            throw "-OutFile is required for Action New."
        }

        $task = Get-TaskEntry -Id $TaskId
        $templatePath = Join-Path $taskRoot $task.Entry.prompt
        $content = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8

        $values = @{
            BATCH_ID = $BatchId
        }

        foreach ($assignment in $Set) {
            if ($assignment -notmatch "^([A-Z0-9_]+)=(.*)$") {
                throw "Invalid -Set value '$assignment'. Expected KEY=VALUE."
            }
            $values[$Matches[1]] = $Matches[2]
        }

        foreach ($key in $values.Keys) {
            $content = $content.Replace("{{${key}}}", [string]$values[$key])
        }

        $unresolved = [regex]::Matches($content, "\{\{([A-Z0-9_]+)\}\}") |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique

        if ($unresolved.Count -gt 0 -and -not $AllowUnresolved) {
            throw "Unresolved placeholders: $($unresolved -join ', ')"
        }

        $resolvedOut = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
        $parent = Split-Path -Parent $resolvedOut
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -LiteralPath $resolvedOut -Value $content -Encoding UTF8
        Write-Output $resolvedOut
        break
    }

    "Validate" {
        if (-not $TaskId) {
            throw "-TaskId is required for Action Validate."
        }
        if (-not $BatchDir) {
            throw "-BatchDir is required for Action Validate."
        }
        if (-not (Test-Path -LiteralPath $validatorPath)) {
            throw "Batch validator not found: $validatorPath"
        }

        $task = Get-TaskEntry -Id $TaskId
        $resolvedBatch = (Resolve-Path -LiteralPath $BatchDir).Path
        & node $validatorPath $resolvedBatch --task $task.Entry.id --format $Format
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        break
    }
}
