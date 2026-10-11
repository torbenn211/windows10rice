# TVA rice: small Linux-flavoured conveniences for PowerShell (5.1 and 7)
function which { param([Parameter(Mandatory)][string]$Name) (Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
function ll { Get-ChildItem -Force @args | Format-Table Mode, LastWriteTime, Length, Name -AutoSize }
function la { Get-ChildItem -Force @args }
function touch { param([Parameter(Mandatory)][string]$Path) if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $Path | Out-Null } }
function mkcd { param([Parameter(Mandatory)][string]$Path) New-Item -ItemType Directory -Force -Path $Path | Out-Null; Set-Location $Path }
function open { param([string]$Path = '.') Invoke-Item $Path }
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function lx { wsl.exe --cd ~ @args }     # jump into Linux
try {
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -Colors @{ Command = 'Yellow'; String = 'DarkYellow'; Parameter = 'DarkGray'; Operator = 'DarkGray'; Variable = 'Green'; Comment = 'DarkGray' }
} catch { }
