# Run launcher in NoLaunch mode, then check Bank TestRunId
$workspaceRoot = "E:\Code\MyMod\SC2"

$projDir = $null
Get-ChildItem -LiteralPath $workspaceRoot -Directory | ForEach-Object {
    $candidate = $_.FullName
    $testPath = Join-Path $candidate "scripts\reborn\launch-reborn-commander.ps1"
    if (Test-Path -LiteralPath $testPath) {
        $projDir = $candidate
    }
}

$launcher = Join-Path $projDir "scripts\reborn\launch-reborn-commander.ps1"
Write-Host "Step 1: Running launcher in NoLaunch mode..." -ForegroundColor Cyan
& $launcher -Commander TerranRaynor -MapName zexpedition03_reborn_port.SC2Map -EnableRuntimeProbe -NoLaunch 2>&1 | Select-Object -Last 20

Write-Host "`nStep 2: Checking Bank TestRunId after launcher..." -ForegroundColor Cyan
$bankPath = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
if (Test-Path -LiteralPath $bankPath) {
    [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
    $testRunIdNode = $xml.Bank.SelectSingleNode("//Section[@name='XMRuntimeControl']/Key[@name='TestRunId']/Value")
    $primaryCmdNode = $xml.Bank.SelectSingleNode("//Section[@name='XMRuntimeControl']/Key[@name='PrimaryCommander']/Value")
    
    Write-Host "  TestRunId: $($testRunIdNode.string)" -ForegroundColor $(if ($testRunIdNode.string) {'Green'} else {'Red'})
    Write-Host "  PrimaryCommander: $($primaryCmdNode.string)" -ForegroundColor $(if ($primaryCmdNode.string) {'Green'} else {'Red'})
    
    # Show all keys in XMRuntimeControl
    $ctrlSection = $xml.Bank.SelectSingleNode("//Section[@name='XMRuntimeControl']")
    if ($ctrlSection) {
        Write-Host "`n  All XMRuntimeControl keys:" -ForegroundColor Yellow
        foreach ($key in $ctrlSection.Key) {
            $val = if ($key.Value.int) { "int=$($key.Value.int)" } elseif ($key.Value.string) { "string=$($key.Value.string)" } else { "(empty)" }
            Write-Host "    $($key.name): $val"
        }
    }
} else {
    Write-Host "  Bank file not found: $bankPath" -ForegroundColor Red
}
