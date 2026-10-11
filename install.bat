@echo off
setlocal
cd /d "%~dp0"
echo TVA Rice - Windows 10
echo This changes user-level application configuration. Review README.txt first.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File | Unblock-File"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo Installer reported an error. Check %%LOCALAPPDATA%%\tva-rice\install.log
) else (
  echo Installer finished. Review warnings above and check the README for verification steps.
)
pause
exit /b %RC%
