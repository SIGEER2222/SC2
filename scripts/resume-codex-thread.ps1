[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ThreadId
)

$ErrorActionPreference = 'Stop'

$codexExe = Join-Path $env:USERPROFILE '.codex\.sandbox-bin\codex.exe'
if (-not (Test-Path $codexExe)) {
    throw "Codex executable not found: $codexExe"
}

$prompt = '继续当前goal，先检查goal状态并继续执行。若已有阻塞，明确记录并推进下一个可执行步骤。'
& $codexExe resume $ThreadId --dangerously-bypass-approvals-and-sandbox --no-alt-screen $prompt
