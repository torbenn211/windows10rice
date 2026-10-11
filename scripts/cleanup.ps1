# TVA rice: safe cleanup. Dry run by default; pass -Run to actually delete.
param([switch]$Run, [int]$OlderThanDays = 3)
$cut = (Get-Date).AddDays(-$OlderThanDays)
$targets = @($env:TEMP, "$env:LOCALAPPDATA\Temp", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | Select-Object -Unique | Where-Object { Test-Path $_ }
$total = 0
foreach ($t in $targets) {
    $files = Get-ChildItem $t -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cut }
    $size = ($files | Measure-Object Length -Sum).Sum; if (-not $size) { $size = 0 }
    $total += $size
    Write-Host ("{0,-60} {1,8:N1} MB in {2} files" -f $t, ($size / 1MB), @($files).Count)
    if ($Run) { $files | Remove-Item -Force -ErrorAction SilentlyContinue }
}
if ($Run) { Write-Host ("Removed about {0:N1} MB (files in use were skipped)." -f ($total / 1MB)) -ForegroundColor Green }
else { Write-Host ("Dry run: about {0:N1} MB could be removed. Re-run with -Run to delete." -f ($total / 1MB)) -ForegroundColor Yellow }
