# TVA rice - uninstaller. Restores backed-up files/settings, removes what the installer added.
param([switch]$KeepApps, [switch]$RemoveApps)

$ErrorActionPreference = 'Continue'
$Data   = Join-Path $env:LOCALAPPDATA 'tva-rice'
$StateF = Join-Path $Data 'state.json'
Start-Transcript -Path (Join-Path $env:TEMP 'tva-rice-uninstall.log') -Append | Out-Null

function Step($m) { Write-Host "`n==> $m" -ForegroundColor DarkYellow }
function Ok($m)   { Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!!] $m" -ForegroundColor Yellow }
function Has-Prop($o, $n) { return ($o.PSObject.Properties.Name -contains $n) }
function Find-Exe($name, $fallbacks) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($f in $fallbacks) { if (Test-Path $f) { return $f } }
    return $null
}
function Restore-V($path, $name, $val, [switch]$Int) {
    if ($null -eq $val) { Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue }
    elseif ($Int) { Set-ItemProperty -Path $path -Name $name -Value ([int]$val) }
    else { Set-ItemProperty -Path $path -Name $name -Value $val }
}

if (-not (Test-Path $StateF)) {
    Write-Host 'No install state found (nothing to undo, or it was already uninstalled).' -ForegroundColor Yellow
    Stop-Transcript | Out-Null; exit 0
}
$State = Get-Content $StateF -Raw | ConvertFrom-Json

Step 'Stopping komorebi, whkd, YASB'
$kom = Find-Exe 'komorebic' @("$env:ProgramFiles\komorebi\bin\komorebic.exe")
if ($kom) {
    & $kom stop --whkd 2>&1 | Out-Null
    & $kom disable-autostart 2>&1 | Out-Null
    Ok 'komorebi stopped, autostart disabled (windows un-cloaked)'
}
Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'YASB (tva-rice).lnk'
if (Test-Path $lnk) { Remove-Item $lnk -Force }
Start-Sleep 1

Step 'Restoring config files'
if (Has-Prop $State 'files') {
    foreach ($f in @($State.files)) {
        if ($f.backup -and (Test-Path $f.backup)) {
            New-Item -ItemType Directory -Force (Split-Path $f.path) | Out-Null
            Copy-Item $f.backup $f.path -Force
            Ok "restored $($f.path)"
        } elseif (Test-Path $f.path) {
            Remove-Item $f.path -Force
            Ok "removed $($f.path)"
        }
    }
}

Step 'Removing Monocraft fonts installed by this rice'
if ((Has-Prop $State 'addedFonts') -and @($State.addedFonts).Count -gt 0) {
    $userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach ($fontName in @($State.addedFonts)) {
        $dest = Join-Path $userFonts $fontName
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
        $regProps = Get-ItemProperty -Path $fontReg -ErrorAction SilentlyContinue
        if ($regProps) {
            foreach ($prop in $regProps.PSObject.Properties) {
                if ($prop.Value -eq $fontName -and $prop.Name -match '^Monocraft') {
                    Remove-ItemProperty -Path $fontReg -Name $prop.Name -ErrorAction SilentlyContinue
                }
            }
        }
    }
    Ok 'removed font files that were added by the rice'
} else {
    Ok 'no rice-installed Monocraft font files to remove'
}

Step 'Removing Windows Terminal fragment'
$frag = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\tva-rice'
if (Test-Path $frag) { Remove-Item $frag -Recurse -Force; Ok 'removed' }

Step 'Removing prompt hook from PowerShell profiles'
$docs = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)
foreach ($p in $profiles) {
    if (Test-Path $p) {
        $t = Get-Content $p -Raw
        if ($t) {
            $clean = [regex]::Replace($t, '(?s)\r?\n?# >>> tva-rice >>>.*?# <<< tva-rice <<<\r?\n?', '')
            [System.IO.File]::WriteAllText($p, $clean, (New-Object System.Text.UTF8Encoding($false)))
        }
    }
}
Ok 'done'

Step 'Restoring system settings'
$pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$adv  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$desk = 'HKCU:\Control Panel\Desktop'
$sr   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
if (Has-Prop $State 'originals') {
    $o = $State.originals
    Restore-V $pers 'AppsUseLightTheme' $o.AppsUseLightTheme -Int
    Restore-V $pers 'SystemUsesLightTheme' $o.SystemUsesLightTheme -Int
    Restore-V $adv 'HideFileExt' $o.HideFileExt -Int
    Restore-V $adv 'Hidden' $o.Hidden -Int
    Restore-V $desk 'WallpaperStyle' $o.WallpaperStyle
    Restore-V $desk 'TileWallpaper' $o.TileWallpaper
    if (-not ('TvaWall' -as [type])) {
        Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class TvaWall {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int a, int b, string c, int d);
}
"@
    }
    if ($o.Wallpaper -and (Test-Path $o.Wallpaper)) { [void][TvaWall]::SystemParametersInfo(0x14, 0, $o.Wallpaper, 3); Ok 'wallpaper restored' }
    if ($null -ne $o.TaskbarByte -and (Test-Path $sr)) {
        $v = (Get-ItemProperty $sr).Settings
        $v[8] = [byte]$o.TaskbarByte
        Set-ItemProperty $sr -Name Settings -Value $v
        Ok 'taskbar auto-hide restored'
    }
    try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $o.ExecutionPolicyCU -Force } catch { }
    Ok 'registry settings restored'
}
if (Has-Prop $State 'regTweaks') {
    foreach ($t in @($State.regTweaks)) {
        try {
            if ($null -eq $t.orig) { Remove-ItemProperty -Path $t.path -Name $t.name -ErrorAction SilentlyContinue }
            elseif ($t.orig -is [string]) { Set-ItemProperty -Path $t.path -Name $t.name -Value $t.orig -Type String }
            else { Set-ItemProperty -Path $t.path -Name $t.name -Value ([int]$t.orig) -Type DWord }
        } catch { Warn "could not restore $($t.name)" }
    }
    Ok 'Windows polish + optimize tweaks restored'
}
if (Has-Prop $State 'powerScheme') {
    try { powercfg /setactive $State.powerScheme 2>&1 | Out-Null; Ok 'power plan restored' } catch { Warn 'could not restore power plan' }
}
if (Has-Prop $State 'originals') {
    try {
        if (-not ('TvaTaskbar' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TvaTaskbar {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct APPBARDATA { public uint cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam; }
    [DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string win);
    public static void SetAutoHide(bool on) {
        APPBARDATA d = new APPBARDATA();
        d.cbSize = (uint)Marshal.SizeOf(typeof(APPBARDATA));
        d.hWnd = FindWindow("Shell_TrayWnd", null);
        d.lParam = (IntPtr)(on ? 1 : 2);
        SHAppBarMessage(0xA, ref d);
    }
}
"@
        }
        [TvaTaskbar]::SetAutoHide(($State.originals.TaskbarByte -eq 3))
        Ok 'taskbar state restored live'
    } catch { Warn 'taskbar restored in registry only; sign out/in' }
}
Write-Host 'Explorer was not forcibly restarted; sign out and back in if shell settings need refreshing.' -ForegroundColor DarkYellow

Step 'Apps'
$doRemove = $false
if ($RemoveApps) { $doRemove = $true }
elseif (-not $KeepApps -and (Has-Prop $State 'installedPackages') -and @($State.installedPackages).Count -gt 0) {
    Write-Host "    Installer added: $(@($State.installedPackages) -join ', ')"
    $a = Read-Host '    Uninstall those apps too? [y/N]'
    if ($a -match '^(y|yes)$') { $doRemove = $true }
}
if ($doRemove -and (Has-Prop $State 'installedPackages')) {
    foreach ($id in @($State.installedPackages)) {
        winget uninstall --id $id -e --silent 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "removed $id" } else { Warn "could not remove $id" }
    }
} else { Ok 'apps kept' }

Remove-Item $Data -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nTVA rice removed. Log out/in if anything still looks off." -ForegroundColor Green
Stop-Transcript | Out-Null
