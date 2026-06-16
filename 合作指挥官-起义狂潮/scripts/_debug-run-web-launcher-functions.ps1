. "$PSScriptRoot\_debug-web-launcher-functions-only.ps1"
$tests = @(
  'Get-CommanderItems',
  'Get-MapItems',
  'Get-MutatorItems',
  'Get-CompletionSnapshot',
  'Get-BootstrapData'
)
foreach($name in $tests){
  try {
    $result = & $name
    Write-Host "$name => OK type=$($result.GetType().FullName) count=$(@($result).Count)"
  } catch {
    Write-Host "$name => FAIL"
    Write-Host $_.Exception.Message
    Write-Host $_.InvocationInfo.PositionMessage
    throw
  }
}
