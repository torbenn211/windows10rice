# Merge the TVA settings template into the current user's VS Code settings.
# Existing keys not mentioned by the template are preserved. Conflicting keys are backed up.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $Root 'config\vscode-settings.json'
$settingsPath = Join-Path $env:APPDATA 'Code\User\settings.json'
if (-not (Test-Path $templatePath)) { throw "Missing template: $templatePath" }
$template = Get-Content $templatePath -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force (Split-Path $settingsPath) | Out-Null
$current = [ordered]@{}
if (Test-Path $settingsPath) {
    $backup = "$settingsPath.tva-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $settingsPath $backup
    $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json
    foreach ($prop in $existing.PSObject.Properties) { $current[$prop.Name] = $prop.Value }
}
foreach ($prop in $template.PSObject.Properties) { $current[$prop.Name] = $prop.Value }
$current | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 $settingsPath
Write-Host "Merged TVA settings into $settingsPath"
if ($backup) { Write-Host "Backup: $backup" }
Write-Host "Restart VS Code to apply all settings."
