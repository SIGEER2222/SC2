<#
.SYNOPSIS
Query the shared Neuro runtime service instead of reading Bank or GameLogs directly.
#>
[CmdletBinding()]
param(
    [ValidateSet("verdict", "events", "state", "status", "health")]
    [string]$Endpoint = "verdict",
    [string]$BaseUrl = "http://127.0.0.1:18080",
    [int]$TimeoutSeconds = 5,
    [switch]$Wait,
    [int]$WaitSeconds = 120,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Get-EndpointPath {
    param([string]$Name)
    switch ($Name) {
        "verdict" { return "/api/verdict" }
        "events" { return "/api/events" }
        "state" { return "/api/state" }
        "status" { return "/api/status" }
        "health" { return "/api/health" }
    }
}

$url = $BaseUrl.TrimEnd("/") + (Get-EndpointPath -Name $Endpoint)
$deadline = (Get-Date).AddSeconds($WaitSeconds)

do {
    try {
        $result = Invoke-RestMethod -Uri $url -TimeoutSec $TimeoutSeconds
        if (-not $Wait -or $Endpoint -ne "verdict" -or $result.ready -or $result.verdict -eq "pass" -or $result.verdict -eq "fail") {
            if ($AsJson) {
                $result | ConvertTo-Json -Depth 12
            } else {
                $result
            }
            if ($Endpoint -eq "verdict") {
                if ($result.verdict -eq "fail") { exit 1 }
                if ($result.verdict -eq "pending") { exit 2 }
            }
            exit 0
        }
    } catch {
        if (-not $Wait) { throw }
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

Write-Error "Timed out waiting for Neuro runtime service endpoint: $url"
exit 2
