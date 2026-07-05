$bankPath = 'C:\Users\22448\Documents\StarCraft II\Banks\CampaignXCore.SC2Bank'
$content = Get-Content $bankPath -Raw -Encoding UTF8

$content = $content -replace '<Section name="Ach">\s*<Key name="Commander">\s*<Value string="[^"]*" />', '<Section name="Ach">
    <Key name="Commander">
      <Value string="TestZerg" />'

$content = $content -replace '<Key name="CommanderP1">\s*<Value string="[^"]*" />', '<Key name="CommanderP1">
      <Value string="TestZerg" />'

$content = $content -replace '<Key name="PrimaryCommander">\s*<Value string="[^"]*" />', '<Key name="PrimaryCommander">
      <Value string="TestZerg" />'

Set-Content $bankPath -Value $content -Encoding UTF8 -NoNewline
Write-Host 'Bank updated to TestZerg'
