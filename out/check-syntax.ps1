$path = 'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\reborn\launch-reborn-commander.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors -and $errors.Count -gt 0) {
    Write-Host "SYNTAX ERRORS ($($errors.Count)):"
    $errors | ForEach-Object { Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" }
    exit 1
} else {
    Write-Host "SYNTAX OK"
    exit 0
}
