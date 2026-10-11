# TVA rice - one-click installer (Windows PowerShell 5.1 or pwsh 7)
param([switch]$SkipWallpaper, [switch]$KeepTaskbar, [switch]$NoPolish, [switch]$NoOptimize, [switch]$AltKeys)

$ErrorActionPreference = 'Stop'
$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cfg    = Join-Path $Root 'config'
$UserHome = $env:USERPROFILE
$Data   = Join-Path $env:LOCALAPPDATA 'tva-rice'
$Backup = Join-Path $Data 'backup'
$StateF = Join-Path $Data 'state.json'

if (-not (Test-Path (Join-Path $Cfg 'whkdrc'))) {
    Write-Host "Can't find the config folder. Extract the whole zip first, don't run this from inside it." -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Force $Data, $Backup | Out-Null
Start-Transcript -Path (Join-Path $Data 'install.log') -Append | Out-Null

function Step($m) { Write-Host "`n==> $m" -ForegroundColor DarkYellow }
function Ok($m)   { Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!!] $m" -ForegroundColor Yellow }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Find-Exe($name, $fallbacks) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($f in $fallbacks) { if (Test-Path $f) { return $f } }
    return $null
}
function Write-Utf8NoBom($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}
function Has-Prop($o, $n) { return ($o.PSObject.Properties.Name -contains $n) }
function SetP($o, $n, $v) { $o | Add-Member -NotePropertyName $n -NotePropertyValue $v -Force }
function GetV($path, $name) { try { (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name } catch { $null } }

function Invoke-Komorebi {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$IgnoreFailure
    )
    # Komorebi writes connection-refused diagnostics when stop/state is called
    # before its IPC server is running. Keep that expected condition from
    # terminating installation under PowerShell's Stop error preference.
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Executable @Arguments 2>&1)
        $code = $LASTEXITCODE
        if ($code -ne 0 -and -not $IgnoreFailure) {
            $summary = ($output | ForEach-Object { "$_" } | Where-Object { $_.Trim() }) -join ' '
            if (-not $summary) { $summary = "exit code $code" }
            throw "komorebic $($Arguments -join ' ') failed: $summary"
        }
        return $code
    } finally {
        $ErrorActionPreference = $oldPreference
    }
}

# ---------- state ----------
if (Test-Path $StateF) { $State = Get-Content $StateF -Raw | ConvertFrom-Json } else { $State = [pscustomobject]@{} }
function Save-State { Write-Utf8NoBom $StateF ($State | ConvertTo-Json -Depth 10) }

function Track-File($path) {
    $files = @(); if (Has-Prop $State 'files') { $files = @($State.files) }
    if ($files | Where-Object { $_.path -eq $path }) { return }   # already tracked: keep the ORIGINAL backup
    $bk = $null
    if (Test-Path $path) {
        $bk = Join-Path $Backup ($path -replace '[:\\/ ]', '_')
        Copy-Item $path $bk -Force
    }
    $files += [pscustomobject]@{ path = $path; backup = $bk }
    SetP $State 'files' $files
    Save-State
}

# ---------- registry paths ----------
$pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$adv  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$desk = 'HKCU:\Control Panel\Desktop'
$sr   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

# ---------- record originals (first run only) ----------
if (-not (Has-Prop $State 'originals')) {
    $tb = $null
    if (Test-Path $sr) { $tb = (Get-ItemProperty $sr).Settings[8] }
    $o = [pscustomobject]@{
        AppsUseLightTheme    = GetV $pers 'AppsUseLightTheme'
        SystemUsesLightTheme = GetV $pers 'SystemUsesLightTheme'
        HideFileExt          = GetV $adv 'HideFileExt'
        Hidden               = GetV $adv 'Hidden'
        Wallpaper            = GetV $desk 'WallPaper'
        WallpaperStyle       = GetV $desk 'WallpaperStyle'
        TileWallpaper        = GetV $desk 'TileWallpaper'
        TaskbarByte          = $tb
        ExecutionPolicyCU    = [string](Get-ExecutionPolicy -Scope CurrentUser)
    }
    SetP $State 'originals' $o
    Save-State
}

# =====================================================================
Step 'Checking winget'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host 'winget not found. Install "App Installer" from the Microsoft Store, then run this again.' -ForegroundColor Red
    Stop-Transcript | Out-Null; exit 1
}
Ok 'winget present'

Step 'Installing packages'
$pkgs = @(
    'LGUG2Z.komorebi', 'LGUG2Z.whkd', 'AmN.yasb',
    'Microsoft.WindowsTerminal', 'JanDeDobbeleer.OhMyPosh',
    'Flow-Launcher.Flow-Launcher', 'DEVCOM.JetBrainsMonoNerdFont'
)
$byUs = @(); if (Has-Prop $State 'installedPackages') { $byUs = @($State.installedPackages) }
foreach ($id in $pkgs) {
    winget list --id $id -e --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "$id already installed"; continue }
    Write-Host "    installing $id ..."
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { $byUs += $id; Ok "$id installed" } else { Warn "$id failed (exit $LASTEXITCODE), continuing" }
}
SetP $State 'installedPackages' $byUs
Save-State
Refresh-Path

# =====================================================================
Step 'Setting up komorebi (tiling WM) + whkd (hotkeys)'
$kom = Find-Exe 'komorebic' @("$env:ProgramFiles\komorebi\bin\komorebic.exe")
if (-not $kom) {
    Warn 'komorebic not found, skipping WM setup. Log out/in and re-run install.bat.'
} else {
    $kcfgHome = $UserHome
    if ($env:KOMOREBI_CONFIG_HOME) { $kcfgHome = $env:KOMOREBI_CONFIG_HOME }
    $kjson = Join-Path $kcfgHome 'komorebi.json'
    $kapps = Join-Path $kcfgHome 'applications.json'
    $whkdHome = Join-Path $UserHome '.config'
    if ($env:WHKD_CONFIG_HOME) { $whkdHome = $env:WHKD_CONFIG_HOME }
    $whkdrc = Join-Path $whkdHome 'whkdrc'

    # Back up any existing files. Do NOT call `komorebic stop` or `quickstart`
    # here: on a first install the IPC server is not running, and the CLI may
    # wait/fail before the installer can continue. Seed a local fallback config
    # only when the user does not already have one.
    Track-File $kjson; Track-File $kapps; Track-File $whkdrc
    if (Test-Path $kjson) {
        Copy-Item $kjson (Join-Path $Data 'komorebi.stock.json') -Force
    } else {
        Warn 'No existing komorebi.json; using the bundled fallback instead of quickstart'
        Copy-Item (Join-Path $Cfg 'komorebi.fallback.json') $kjson -Force
        Copy-Item $kjson (Join-Path $Data 'komorebi.stock.json') -Force
    }

    # Install the bundled TVA config whole (gaps, square borders, smooth animation,
    # workspaces 1-9) instead of patching the user's JSON, which was fragile.
    Copy-Item (Join-Path $Cfg 'komorebi.json') $kjson -Force
    Ok 'komorebi.json installed (square borders, smooth animation, workspaces 1-9)'

    # Community per-app rules so dialogs, pickers and odd apps are not tiled wrongly.
    Invoke-Komorebi -Executable $kom -Arguments @('fetch-asc') -IgnoreFailure | Out-Null
    if (Test-Path $kapps) {
        $ascPath = ($kapps -replace '\\', '/')
        $txt = Get-Content $kjson -Raw
        $txt = [regex]::Replace($txt, '^\{', ('{' + "`n" + '  "app_specific_configuration_path": "' + $ascPath + '",'), 1)
        Write-Utf8NoBom $kjson $txt
        Ok 'app-specific rules (applications.json) downloaded and enabled'
    } else {
        Warn 'could not download applications.json (offline?). Run "komorebic fetch-asc" later.'
    }

    # ---- keybinds: pick terminal/file manager commands that actually work on this PC ----
    function Test-WslReady {
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
        try {
            $o = (& wsl.exe --list --quiet 2>$null | Out-String) -replace "`0", ''
            if ($LASTEXITCODE -ne 0) { return $false }
            return [bool](@($o -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^docker-desktop' }).Count)
        } catch { return $false }
    }
    $wslReady = Test-WslReady
    $wslDistro = $null
    if ($wslReady) {
        $names = @(((& wsl.exe --list --quiet 2>$null | Out-String) -replace "`0", '') -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^docker-desktop' })
        $wslDistro = ($names | Where-Object { $_ -match '^arch' } | Select-Object -First 1)
        if (-not $wslDistro) { $wslDistro = $names | Select-Object -First 1 }
    }
    if ($wslReady -and $wslDistro) {
        $tTerm = 'wt -p "TVA Linux"'
        $tBtop = 'wt -p "TVA Linux" wsl.exe -d ' + $wslDistro + ' --cd ~ -e btop'
        $tNvim = 'wt -p "TVA Linux" wsl.exe -d ' + $wslDistro + ' --cd ~ -e nvim'
        Ok "WSL detected ($wslDistro): Win+Enter opens your Linux shell"
        if ($wslDistro -notmatch '^arch') { Warn 'Not Arch. Run scripts\setup-wsl.ps1 to install Arch Linux, then re-run install.bat.' }
    } else {
        $wslReady = $false
        $tTerm = 'wt'
        $tBtop = 'taskmgr.exe'
        $tNvim = 'code'
        Warn 'No working WSL distro: Win+Enter opens PowerShell. Run scripts\setup-wsl.ps1 to add Arch Linux.'
    }
    $tFiles = 'explorer.exe'
    $rcSrc = if ($AltKeys) { 'whkdrc.alt' } else { 'whkdrc' }
    $rc = Get-Content (Join-Path $Cfg $rcSrc) -Raw
    $rc = $rc.Replace('__TERM__', $tTerm).Replace('__BTOP__', $tBtop).Replace('__NVIM__', $tNvim).Replace('__FILES__', $tFiles)
    New-Item -ItemType Directory -Force $whkdHome | Out-Null
    Write-Utf8NoBom $whkdrc $rc
    Ok "whkdrc installed ($rcSrc)"

    Start-Sleep 1
    # Avoid stop-before-start. Start is the only command needed for a fresh setup.
    Invoke-Komorebi -Executable $kom -Arguments @('start', '--whkd') -IgnoreFailure | Out-Null
    Start-Sleep 4
    $stateCode = Invoke-Komorebi -Executable $kom -Arguments @('state') -IgnoreFailure
    if ($stateCode -ne 0) {
        Warn 'komorebi did not come up with the patched config, reverting to the plain fallback config (no animation)'
        Copy-Item (Join-Path $Cfg 'komorebi.fallback.json') $kjson -Force
        Invoke-Komorebi -Executable $kom -Arguments @('stop', '--whkd') -IgnoreFailure | Out-Null
        Start-Sleep 1
        Invoke-Komorebi -Executable $kom -Arguments @('start', '--whkd') -IgnoreFailure | Out-Null
        Start-Sleep 3
        $stateCode = Invoke-Komorebi -Executable $kom -Arguments @('state') -IgnoreFailure
        if ($stateCode -ne 0) {
            Warn 'komorebi is still not responding. Installation will continue, but tiling/hotkeys may be unavailable. See install.log and run diagnose.ps1.'
        } else {
            Ok 'komorebi running with stock config'
        }
    } else {
        Ok 'komorebi running'
    }
    Invoke-Komorebi -Executable $kom -Arguments @('enable-autostart', '--whkd') -IgnoreFailure | Out-Null
    Ok 'komorebi + whkd autostart enabled'
}

# =====================================================================
Step 'Setting up YASB (bar)'
$yasbDir = Join-Path $UserHome '.config\yasb'
New-Item -ItemType Directory -Force $yasbDir | Out-Null
Track-File (Join-Path $yasbDir 'config.yaml')
Track-File (Join-Path $yasbDir 'styles.css')
Copy-Item (Join-Path $Cfg 'yasb\config.yaml') (Join-Path $yasbDir 'config.yaml') -Force
Copy-Item (Join-Path $Cfg 'yasb\styles.css')  (Join-Path $yasbDir 'styles.css') -Force
if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) {
    $yc = Join-Path $yasbDir 'config.yaml'
    Write-Utf8NoBom $yc ((Get-Content $yc -Raw).Replace('"memory", "volume"]', '"memory", "volume", "battery"]'))
    Ok 'battery detected: battery widget added to the bar'
}
Ok 'YASB config + styles installed'

$yasbExe = $null
foreach ($d in @("$env:ProgramFiles\YASB", "${env:ProgramFiles(x86)}\YASB", "$env:LOCALAPPDATA\Programs\YASB")) {
    if (Test-Path (Join-Path $d 'yasb.exe')) { $yasbExe = Join-Path $d 'yasb.exe'; break }
}
if (-not $yasbExe) {
    $yc = Get-Command yasbc -ErrorAction SilentlyContinue
    if ($yc) { $cand = Join-Path (Split-Path $yc.Source) 'yasb.exe'; if (Test-Path $cand) { $yasbExe = $cand } }
}
if ($yasbExe) {
    Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Process $yasbExe -WorkingDirectory (Split-Path $yasbExe)
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'YASB (tva-rice).lnk'
    $sh = New-Object -ComObject WScript.Shell
    $sc = $sh.CreateShortcut($lnk)
    $sc.TargetPath = $yasbExe
    $sc.WorkingDirectory = Split-Path $yasbExe
    $sc.WindowStyle = 7
    $sc.Save()
    Ok 'YASB started + added to startup'
} else {
    Warn 'yasb.exe not found. Launch YASB from the Start menu once, it will pick up the config.'
}

# =====================================================================
Step 'Installing Monocraft fonts for current user'
$fontSource = Join-Path $Root 'assets\fonts'
if (Test-Path $fontSource) {
    $userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force $userFonts | Out-Null
    $fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -Path $fontReg -Force | Out-Null
    $addedFonts = @()
    if (Has-Prop $State 'addedFonts') { $addedFonts = @($State.addedFonts) }
    foreach ($font in Get-ChildItem $fontSource -Filter '*.ttf' -File) {
        $dest = Join-Path $userFonts $font.Name
        if (-not (Test-Path $dest)) {
            Copy-Item $font.FullName $dest
            $addedFonts += $font.Name
            $display = switch -Regex ($font.Name) {
                'Bold-Italic' { 'Monocraft Bold Italic (TrueType)'; break }
                'Bold'        { 'Monocraft Bold (TrueType)'; break }
                'Italic'      { 'Monocraft Italic (TrueType)'; break }
                default       { 'Monocraft (TrueType)' }
            }
            New-ItemProperty -Path $fontReg -Name $display -Value $font.Name -PropertyType String -Force | Out-Null
        }
    }
    SetP $State 'addedFonts' @($addedFonts | Select-Object -Unique)
    Save-State
    Ok 'Monocraft fonts copied for current user; restart apps to refresh fonts'
} else {
    Warn 'Monocraft font assets missing; terminal/bar will use fallback fonts'
}

Step 'Windows Terminal theme (fragment, no settings.json edits)'
$frag = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\tva-rice'
New-Item -ItemType Directory -Force $frag | Out-Null
Copy-Item (Join-Path $Cfg 'windows-terminal\tva.json') (Join-Path $frag 'tva.json') -Force
if ($wslReady -and $wslDistro) { Write-Utf8NoBom (Join-Path $frag 'tva-linux.json') ((Get-Content (Join-Path $Cfg 'windows-terminal\tva-linux.json') -Raw).Replace('__DISTRO__', $wslDistro)); Ok 'added "TVA Linux" Terminal profile' }
elseif (Test-Path (Join-Path $frag 'tva-linux.json')) { Remove-Item (Join-Path $frag 'tva-linux.json') -Force }
Ok 'TVA scheme added. If your terminal still looks stock: Settings > Profiles > Appearance > Color scheme > TVA'

Step 'Oh My Posh prompt'
Copy-Item (Join-Path $Cfg 'ohmyposh\tva.omp.json') (Join-Path $Data 'tva.omp.json') -Force
$docs = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)
$begin = '# >>> tva-rice >>>'
$end   = '# <<< tva-rice <<<'
Copy-Item (Join-Path $Cfg 'powershell\tva-profile.ps1') (Join-Path $Data 'tva-profile.ps1') -Force
$block = @"
$begin
if (Test-Path "`$env:LOCALAPPDATA\tva-rice\tva-profile.ps1") { . "`$env:LOCALAPPDATA\tva-rice\tva-profile.ps1" }
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { oh-my-posh init pwsh --config "`$env:LOCALAPPDATA\tva-rice\tva.omp.json" | Invoke-Expression }
$end
"@
foreach ($p in $profiles) {
    New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
    $existing = ''
    if (Test-Path $p) { $existing = Get-Content $p -Raw; if ($null -eq $existing) { $existing = '' } }
    if ($existing -match [regex]::Escape($begin)) {
        $existing = [regex]::Replace($existing, '(?s)\r?\n?# >>> tva-rice >>>.*?# <<< tva-rice <<<\r?\n?', '')
        Write-Utf8NoBom $p $existing
    }
    Add-Content -Path $p -Value ("`r`n" + $block + "`r`n")
}
try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force } catch { Warn 'could not set execution policy (GPO?), prompt may not load' }
Ok 'prompt hooked into PowerShell profiles'

# =====================================================================
Step 'System tweaks (dark mode, file extensions, hidden files)'
Set-ItemProperty $pers -Name AppsUseLightTheme -Value 0
Set-ItemProperty $pers -Name SystemUsesLightTheme -Value 0
Set-ItemProperty $adv  -Name HideFileExt -Value 0
Set-ItemProperty $adv  -Name Hidden -Value 1
Ok 'done'

function ToDw([string]$hex) { [BitConverter]::ToInt32([BitConverter]::GetBytes([Convert]::ToUInt32($hex, 16)), 0) }
function Apply-Tweaks($list) {
    $rec = @(); if (Has-Prop $State 'regTweaks') { $rec = @($State.regTweaks) }
    foreach ($t in $list) {
        # t = path, name, value, type ('D' DWord or 'S' String)
        try {
            if (-not (Test-Path $t[0])) { New-Item -Path $t[0] -Force | Out-Null }
            if (-not ($rec | Where-Object { $_.path -eq $t[0] -and $_.name -eq $t[1] })) {
                $rec += [pscustomobject]@{ path = $t[0]; name = $t[1]; orig = (GetV $t[0] $t[1]) }
                SetP $State 'regTweaks' $rec; Save-State
            }
            if ($t[3] -eq 'S') { Set-ItemProperty -Path $t[0] -Name $t[1] -Value ([string]$t[2]) -Type String }
            else               { Set-ItemProperty -Path $t[0] -Name $t[1] -Value ([int]$t[2]) -Type DWord }
        } catch { Warn "could not set $($t[1]): $($_.Exception.Message)" }
    }
}
$dwm   = 'HKCU:\Software\Microsoft\Windows\DWM'
$srch  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
$feeds = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'
$cab   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'
$expl  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$cdm   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

if (-not $NoPolish) {
    Step 'Windows polish (amber title bars, flat look, clean desktop/taskbar/Explorer)'
    Apply-Tweaks @(
        @($dwm,  'AccentColor',         (ToDw 'FF2483D9'), 'D'),   # amber #D98324 (ABGR)
        @($dwm,  'AccentColorInactive', (ToDw 'FF1D252A'), 'D'),
        @($dwm,  'ColorizationColor',   (ToDw 'C4D98324'), 'D'),
        @($dwm,  'ColorPrevalence',     1, 'D'),                   # accent on title bars + borders
        @($pers, 'EnableTransparency',  0, 'D'),                   # flat, no acrylic blur
        @($adv,  'HideIcons',           1, 'D'),                   # clean desktop, wallpaper only
        @($adv,  'ShowTaskViewButton',  0, 'D'),
        @($adv,  'ShowCortanaButton',   0, 'D'),
        @($adv,  'DisallowShaking',     1, 'D'),                   # Aero Shake fights a tiler
        @($adv,  'LaunchTo',            1, 'D'),                   # Explorer opens This PC
        @($adv,  'MultiTaskingAltTabFilter', 3, 'D'),              # Alt+Tab: windows only, no browser tabs
        @($adv,  'SnapAssist',          0, 'D'),                   # Aero Snap fights the tiler
        @($desk, 'WindowArrangementActive', '0', 'S'),
        @($srch, 'SearchboxTaskbarMode',0, 'D'),
        @($feeds,'ShellFeedsTaskbarViewMode', 2, 'D'),             # no News and interests
        @($cab,  'FullPath',            1, 'D'),                   # full path in Explorer title bar
        @($expl, 'ShowFrequent',        0, 'D'),
        @($expl, 'ShowRecent',          0, 'D'),
        @($adv,  'ShowStatusBar',       1, 'D'),                   # classic status bar in Explorer
        @($adv,  'IconsOnly',           1, 'D'),                   # icons, not thumbnails (classic + faster)
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon', 'MinimizedStateTabletModeOff', 1, 'D'),
        @('HKCU:\AppEvents\Schemes', '(default)', '.None', 'S')   # no system sounds, quiet like a terminal
    )
    Ok 'applied. Sign out and back in to see title-bar colors and icon changes.'
}

if (-not $NoOptimize) {
    Step 'Optimizing Windows (per-user, reversible: input, privacy, background load)'
    Apply-Tweaks @(
        # input: Linux-style fast key repeat, no mouse acceleration, no sticky-key popups
        @('HKCU:\Control Panel\Keyboard', 'KeyboardDelay', '0', 'S'),
        @('HKCU:\Control Panel\Keyboard', 'KeyboardSpeed', '31', 'S'),
        @('HKCU:\Control Panel\Mouse', 'MouseSpeed', '0', 'S'),
        @('HKCU:\Control Panel\Mouse', 'MouseThreshold1', '0', 'S'),
        @('HKCU:\Control Panel\Mouse', 'MouseThreshold2', '0', 'S'),
        @('HKCU:\Control Panel\Accessibility\StickyKeys', 'Flags', '506', 'S'),
        @('HKCU:\Control Panel\Accessibility\ToggleKeys', 'Flags', '58', 'S'),
        @('HKCU:\Control Panel\Accessibility\Keyboard Response', 'Flags', '122', 'S'),
        # less background load
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications', 'GlobalUserDisabled', 1, 'D'),
        @($srch, 'BackgroundAppGlobalToggle', 0, 'D'),
        @($srch, 'BingSearchEnabled', 0, 'D'),                     # no web results in Start search
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize', 'StartupDelayInMSec', 0, 'D'),
        @('HKCU:\System\GameConfigStore', 'GameDVR_Enabled', 0, 'D'),
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR', 'AppCaptureEnabled', 0, 'D'),
        @($adv,  'ShowSyncProviderNotifications', 0, 'D'),         # no OneDrive/Store nags in Explorer
        # privacy / tips / suggested apps
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled', 0, 'D'),
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled', 0, 'D'),
        @($cdm, 'SubscribedContent-338387Enabled', 0, 'D'),
        @($cdm, 'SubscribedContent-338388Enabled', 0, 'D'),
        @($cdm, 'SubscribedContent-338389Enabled', 0, 'D'),
        @($cdm, 'SubscribedContent-338393Enabled', 0, 'D'),
        @($cdm, 'SubscribedContent-353694Enabled', 0, 'D'),
        @($cdm, 'SubscribedContent-353696Enabled', 0, 'D'),
        @($cdm, 'SystemPaneSuggestionsEnabled', 0, 'D'),
        @($cdm, 'SilentInstalledAppsEnabled', 0, 'D'),
        @($cdm, 'SoftLandingEnabled', 0, 'D'),
        @($cdm, 'RotatingLockScreenOverlayEnabled', 0, 'D')
    )
    # Power plan: High performance on desktops only (laptops keep their current plan for battery life)
    try {
        if (-not (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)) {
            $cur = (powercfg /getactivescheme) -replace '.*:\s*([0-9a-fA-F-]{36}).*', '$1'
            if (-not (Has-Prop $State 'powerScheme')) { SetP $State 'powerScheme' $cur; Save-State }
            powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
            Ok 'desktop detected: power plan set to High performance'
        } else { Ok 'laptop detected: power plan left alone' }
    } catch { Warn 'could not change power plan' }
    Ok 'optimizations applied (no services disabled, no security settings touched). Sign out/in for input changes.'
}

if (-not $SkipWallpaper) {
    Step 'Wallpaper'
    $wp = Join-Path $Data 'wallpaper.png'
    Copy-Item (Join-Path $Cfg 'wallpaper.png') $wp -Force
    Set-ItemProperty $desk -Name WallpaperStyle -Value '10'
    Set-ItemProperty $desk -Name TileWallpaper -Value '0'
    if (-not ('TvaWall' -as [type])) {
        Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class TvaWall {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int a, int b, string c, int d);
}
"@
    }
    [void][TvaWall]::SystemParametersInfo(0x14, 0, $wp, 3)
    Ok 'wallpaper set'
}

Step 'Taskbar behavior'
if ($KeepTaskbar) {
    Ok 'native taskbar left as it was (-KeepTaskbar)'
} else {
    if (Test-Path $sr) {
        $v = (Get-ItemProperty $sr).Settings
        $v[8] = 3
        Set-ItemProperty -Path $sr -Name Settings -Value $v
    }
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
    try { [TvaTaskbar]::SetAutoHide($true); Ok 'taskbar set to auto-hide (applied live, Explorer not restarted)' }
    catch { Warn 'taskbar auto-hide saved but could not apply live; sign out/in' }
    Ok 'Recovery: Ctrl+Shift+Esc = Task Manager, Win key = Start menu, uninstall.bat restores the taskbar.'
}

Save-State
Write-Host "`n=====================================" -ForegroundColor DarkYellow
Write-Host ' TVA rice installed.' -ForegroundColor Green
Write-Host ' win+enter terminal | win+shift+f files | win+w close | win+arrows focus | win+1-9 workspace'
Write-Host ' Full list: %USERPROFILE%\.config\whkdrc'
Write-Host " Log: $Data\install.log"
Write-Host ' Linux: run scripts\setup-wsl.ps1  |  Undo everything: run uninstall.bat'
Write-Host '=====================================' -ForegroundColor DarkYellow
Stop-Transcript | Out-Null
