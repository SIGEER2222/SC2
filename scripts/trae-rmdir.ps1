Remove-Item -Path $args[0] -Force -Recurse -ErrorAction SilentlyContinue
if (Test-Path $args[0]) {
    Write-Error "Failed to remove directory: $($args[0])"
    exit 1
} else {
    Write-Output "Removed directory: $($args[0])"
    exit 0
}
