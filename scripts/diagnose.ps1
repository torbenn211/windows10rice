# TVA diagnostics: read-only checks for core commands, files, WSL, and startup load.
$ErrorActionPreference = 'Continue'
Write-Host "`nTVA Rice diagnostics" -ForegroundColor Cyan
foreach ($name in @('komorebic','whkd','wt','winget','wsl','oh-my-posh')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { Write-Host "[OK] $name -> $($cmd.Source)" -ForegroundColor Green }
    else { Write-Host "[MISSING] $name" -ForegroundColor Yellow }
}
$cfgs = @(
    (Join-Path $env:USERPROFILE 'komorebi.json'),
    (Join-Path $env:USERPROFILE 'applications.json'),
    (Join-Path $env:USERPROFILE '.config\whkdrc'),
    (Join-Path $env:USERPROFILE '.config\yasb\config.yaml'),
    (Join-Path $env:USERPROFILE '.config\yasb\styles.css')
)
foreach ($file in $cfgs) {
    if (Test-Path $file) { Write-Host "[OK] $file" -ForegroundColor Green }
    else { Write-Host "[MISSING] $file" -ForegroundColor Yellow }
}
Write-Host "`nRunning rice processes:"
Get-Process komorebi,whkd,yasb -ErrorAction SilentlyContinue |
    Select-Object ProcessName,Id,@{n='CPU(s)';e={[math]::Round($_.CPU,1)}},@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB)}} | Format-Table -AutoSize
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) { Write-Host 'WSL distros:'; wsl.exe --list --verbose }
Write-Host "`nStartup items (candidates to disable in Task Manager > Startup):"
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object Name, Location | Format-Table -AutoSize
Write-Host 'Read-only diagnostic complete. It does not restart or modify anything.'
