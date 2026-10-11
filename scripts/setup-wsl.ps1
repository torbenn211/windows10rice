# TVA rice: install + configure Arch Linux on WSL2 (official image). Run from PowerShell.
# Needs admin + possibly a restart the first time. Safe to re-run.
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
function Ok($m)   { Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!!] $m" -ForegroundColor Yellow }

$build = [Environment]::OSVersion.Version.Build
if ($build -lt 19041) { Warn "Windows build $build is too old for WSL2 (needs 19041+). Update Windows first."; Read-Host 'Enter to close'; exit 1 }

function Get-Distros {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return @() }
    $out = (& wsl.exe --list --quiet 2>$null | Out-String) -replace "`0", ''
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^docker-desktop' })
}
$arch = Get-Distros | Where-Object { $_ -match '^arch' } | Select-Object -First 1

if (-not $arch) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) {
        Write-Host 'Arch is not installed yet. Re-launching as administrator...' -ForegroundColor DarkYellow
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit 0
    }
    Write-Host 'Updating WSL and installing Arch Linux (official image)...' -ForegroundColor DarkYellow
    wsl.exe --update 2>&1 | Out-Null
    wsl.exe --install -d archlinux --no-launch
    $arch = Get-Distros | Where-Object { $_ -match '^arch' } | Select-Object -First 1
    if (-not $arch) {
        Write-Host "`nIf Windows asks for a restart, do it, then run this script again." -ForegroundColor Yellow
        Write-Host 'If it says archlinux is unknown, run: wsl --update   and check: wsl --list --online' -ForegroundColor Yellow
        Read-Host 'Press Enter to close'
        exit 0
    }
}
Ok "Arch distro: $arch"

$wslcfg = Join-Path $env:USERPROFILE '.wslconfig'
if (-not (Test-Path $wslcfg)) {
    "[experimental]`r`nautoMemoryReclaim=gradual`r`nsparseVhd=true`r`n" | Set-Content $wslcfg -Encoding ASCII
    Ok '.wslconfig created (gives RAM back to Windows, keeps the disk image small)'
} else { Ok '.wslconfig already exists, left untouched' }

$user = Read-Host 'Choose your Linux username (lowercase, no spaces)'
if ($user -notmatch '^[a-z_][a-z0-9_-]{0,30}$') { Warn 'Invalid username.'; exit 1 }

$sh = (Get-Content (Join-Path $Root 'config\wsl\arch-setup.sh') -Raw) -replace "`r`n", "`n"
$sh | wsl.exe -d $arch -u root -e bash -c 'cat > /root/tva-arch-setup.sh'
wsl.exe -d $arch -u root -e bash /root/tva-arch-setup.sh $user
if ($LASTEXITCODE -ne 0) { Warn 'Setup script reported an error. Scroll up, fix it, and run this script again.'; Read-Host 'Enter to close'; exit 1 }

Write-Host "`nSet a password for $user (needed for sudo):" -ForegroundColor DarkYellow
wsl.exe -d $arch -u root -e passwd $user
wsl.exe --set-default $arch
wsl.exe --terminate $arch
Ok 'Arch configured. Now re-run install.bat so Win+Enter and the TVA Linux profile point at Arch.'
Read-Host 'Press Enter to close'
