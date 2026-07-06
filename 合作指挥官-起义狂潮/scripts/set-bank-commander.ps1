param(
    [string]$Commander = "Kerrigan",
    [string]$BankPath = "C:\Users\22448\Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
)

if (-not (Test-Path -LiteralPath $BankPath)) {
    Write-Host "Bank file not found: $BankPath" -ForegroundColor Red
    exit 1
}

Write-Host "Setting PrimaryCommander to $Commander in $BankPath"

$xml = [xml](Get-Content -LiteralPath $BankPath -Raw -Encoding UTF8)

$sections = @("XMRuntimeControl", "Ach")
foreach ($secName in $sections) {
    $sec = $xml.Bank.Section | Where-Object { $_.name -eq $secName }
    if (-not $sec) {
        Write-Host "  Section $secName not found, skip" -ForegroundColor Yellow
        continue
    }
    foreach ($keyName in @("PrimaryCommander", "CommanderP1", "Commander")) {
        $key = $sec.Key | Where-Object { $_.name -eq $keyName }
        if ($key) {
            $oldVal = $key.Value.InnerText
            $key.Value.SetAttribute("string", $Commander) | Out-Null
            Write-Host ("  {0}.{1}: '{2}' -> '{3}'" -f $secName, $keyName, $oldVal, $Commander) -ForegroundColor Green
        }
    }
}

$xml.Save($BankPath)
Write-Host "Done" -ForegroundColor Cyan
