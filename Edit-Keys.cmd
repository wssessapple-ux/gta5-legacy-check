@echo off
setlocal
cd /d "%~dp0"

where pwsh >nul 2>nul
if errorlevel 1 (
    set "PSEXE=powershell"
) else (
    set "PSEXE=pwsh"
    chcp 65001 >nul
)

if "%~1"=="" (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Edit-Keys.ps1"
) else (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Edit-Keys.ps1" -Ini "%~1"
)

if errorlevel 1 pause