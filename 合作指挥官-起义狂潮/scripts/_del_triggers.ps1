$base = "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map"
$files = @("Triggers", "Triggers.version")
foreach ($f in $files) {
    $p = Join-Path $base $f
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Force
        Write-Host "Deleted: $p"
    } else {
        Write-Host "Not found: $p"
    }
}
Write-Host "Done"
