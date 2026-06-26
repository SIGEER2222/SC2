Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue
if (Test-Path $args[0]) {
    Write-Error "Failed to delete: $($args[0])"
    exit 1
} else {
    Write-Output "Deleted: $($args[0])"
    exit 0
}
