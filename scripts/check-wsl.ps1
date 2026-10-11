# TVA WSL setup helper — opt-in, non-destructive.
# Checks Windows build and WSL availability. It does not enable features or reboot.
$ErrorActionPreference = 'Continue'
$build = [Environment]::OSVersion.Version.Build
Write-Host "Windows build: $build"
if ($build -lt 18362) {
    Write-Warning "This Windows 10 build is below the usual WSL2 prerequisite range. Update Windows before attempting WSL2."
    exit 2
}
if ($build -lt 19041) {
    Write-Warning "WSL2 may require additional updates on this build. A current supported Windows 10 build is recommended."
}
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Warning "wsl.exe was not found. WSL may not be installed or enabled."
    Write-Host "Follow Microsoft's Windows-version-specific WSL setup instructions, then restart if requested."
    exit 1
}
Write-Host "`nInstalled distributions:"
& wsl.exe --list --verbose
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not list WSL distributions. Check Windows features, virtualization, and WSL installation."
    exit 1
}
Write-Host "`nThis script does not install a distribution, enable Windows features, or reboot automatically."
