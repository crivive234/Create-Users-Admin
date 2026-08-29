@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo Running IT support user manager...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ITSupportUser.ps1" %*
echo.
echo Done. You can close this window.
pause