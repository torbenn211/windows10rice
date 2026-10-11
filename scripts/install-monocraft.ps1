# Installs bundled Monocraft fonts for the current Windows user.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$FontDir = Join-Path $Root 'assets\fonts'
$UserFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$RegPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Force $UserFonts | Out-Null
New-Item -Path $RegPath -Force | Out-Null
$installed = @()
$fontFiles = Get-ChildItem $FontDir -Filter '*.ttf' -File
foreach ($font in $fontFiles) {
    $dest = Join-Path $UserFonts $font.Name
    if (-not (Test-Path $dest)) {
        Copy-Item $font.FullName $dest
        $installed += $font.Name
    }
    $display = switch -Regex ($font.Name) {
        'Bold-Italic' { 'Monocraft Bold Italic (TrueType)'; break }
        'Bold'        { 'Monocraft Bold (TrueType)'; break }
        'Italic'      { 'Monocraft Italic (TrueType)'; break }
        default       { 'Monocraft (TrueType)' }
    }
    New-ItemProperty -Path $RegPath -Name $display -Value $font.Name -PropertyType String -Force | Out-Null
}
Write-Host "Monocraft user fonts configured. Restart apps to refresh their font lists."
Write-Host "Font files copied during this run: $($installed -join ', ')"
