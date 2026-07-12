# Test regex behavior for LibRuntimeProbe include detection
$content = @'
include "LibE0EAE146"
include "LibRuntimeProbe"

void InitLibs () {
}
'@

Write-Host "=== Content ==="
Write-Host $content
Write-Host ""

# Current regex (buggy)
$needHeader1 = $content -notmatch 'include\s+"LibRuntimeProbe_h"'
$needImpl1   = $content -notmatch 'include\s+"LibRuntimeProbe"\s'
Write-Host "Current regex:"
Write-Host "  needHeader (LibRuntimeProbe_h): $needHeader1"
Write-Host "  needImpl   (LibRuntimeProbe\s): $needImpl1"
Write-Host ""

# Why needImpl is false: \s matches the newline after "
$matchResult = $content -match 'include\s+"LibRuntimeProbe"\s'
Write-Host "  'include\s+""LibRuntimeProbe""\s' matched: $matchResult"
Write-Host ""

# Fixed regex with line anchor
$needHeader2 = $content -notmatch '(?m)^\s*include\s+"LibRuntimeProbe_h"\s*$'
$needImpl2   = $content -notmatch '(?m)^\s*include\s+"LibRuntimeProbe"\s*$'
Write-Host "Fixed regex (line-anchored):"
Write-Host "  needHeader: $needHeader2"
Write-Host "  needImpl:   $needImpl2"
