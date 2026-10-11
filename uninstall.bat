@echo off
setlocal
cd /d "%~dp0"
echo TVA Rice uninstaller
echo This restores tracked user settings and stops the custom desktop components.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Uninstaller reported an error. Review the output and logs.
pause
exit /b %RC%
